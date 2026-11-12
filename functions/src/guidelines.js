// =======================================================
// SEARCH GUIDELINES (Ask NutriPal tool)
// =======================================================
//
// Finds validated NutriPal knowledge-base entries for a
// question. The entries are packaged with the function
// (knowledge/chatbot_kb.json): only source-verified or
// evidence-derived entries approved for direct use,
// contextual guidance or chatbot education.
//
// Retrieval is deterministic keyword matching, not
// embeddings, so the same question always finds the same
// entries and every answer can be traced to entry IDs:
//
//   1. Words in the query and in each entry are mapped
//      to shared concepts (English and Bahasa Melayu
//      synonyms, e.g. "garam" -> salt).
//   2. Score = 2 per concept in the entry topic + 1 per
//      concept in its guidance text.
//   3. Entries for the user's health areas (and general
//      entries) are searched unless another area is
//      asked for. A score of at least 2 is needed.
//   4. The best MAX_RESULTS entries are returned. None
//      found -> found: false, and the model must say
//      there isn't enough validated information.
//
// The score threshold and synonym list are researcher-
// defined (tuned on the test questions in Chapter 4).
// =======================================================

'use strict';

const KB = require('./knowledge/chatbot_kb.json');

const MAX_RESULTS = 4;
const MIN_SCORE = 2;

const AREAS = ['Diabetes', 'Blood pressure', 'Cholesterol', 'Weight', 'General'];

// concept -> words that mean it (English + Malay).
const CONCEPTS = {
  sugar: ['sugar', 'sugars', 'sugary', 'sweet', 'sucrose', 'gula', 'manis'],
  sweetener: ['sweetener', 'sweeteners', 'aspartame', 'stevia', 'sucralose', 'pemanis', 'non-nutritive'],
  salt: ['salt', 'salty', 'sodium', 'msg', 'garam', 'masin', 'natrium', 'kicap'],
  fat: ['fat', 'fats', 'lemak', 'berlemak'],
  saturated: ['saturated', 'tepu'],
  trans: ['trans'],
  cholesterol: ['cholesterol', 'kolesterol', 'ldl', 'lipid', 'lipids', 'dyslipidaemia'],
  triglyceride: ['triglyceride', 'triglycerides', 'trigliserida', 'tg'],
  fibre: ['fibre', 'fiber', 'serat', 'serabut'],
  carbohydrate: ['carbohydrate', 'carbohydrates', 'carb', 'carbs', 'karbohidrat', 'starch', 'kanji', 'rice', 'nasi', 'bread', 'roti'],
  glycaemic: ['gi', 'glycaemic', 'glycemic', 'glisemik', 'low-gi'],
  energy: ['energy', 'calorie', 'calories', 'kcal', 'kalori', 'tenaga', 'eer'],
  weight: ['weight', 'berat', 'obesity', 'obese', 'obes', 'overweight', 'gemuk', 'kurus', 'slim', 'bmi'],
  lose: ['lose', 'losing', 'loss', 'turun', 'kurangkan', 'deficit'],
  gain: ['gain', 'gaining', 'naik', 'tambah'],
  activity: ['activity', 'active', 'exercise', 'senaman', 'aktiviti', 'walk', 'walking', 'bersenam'],
  alcohol: ['alcohol', 'alkohol', 'beer', 'wine', 'arak'],
  drink: ['drink', 'drinks', 'beverage', 'beverages', 'minuman', 'minum', 'juice', 'juices', 'jus', 'soda', 'soft'],
  water: ['water', 'air', 'kosong'],
  potassium: ['potassium', 'kalium'],
  substitute: ['substitute', 'substitutes', 'pengganti'],
  protein: ['protein'],
  coffee: ['coffee', 'kopi'],
  tea: ['tea', 'teh'],
  label: ['label', 'labels', 'claim', 'claims', 'pelabelan'],
  low: ['low', 'rendah', 'less', 'kurang', 'reduced'],
  processed: ['processed', 'ultra-processed', 'diproses'],
  oil: ['oil', 'oils', 'minyak', 'palm', 'sawit', 'coconut', 'kelapa', 'santan', 'butter', 'mentega', 'tropical'],
  portion: ['portion', 'portions', 'serving', 'servings', 'hidangan', 'sajian'],
  noodle: ['noodle', 'noodles', 'mee', 'mi'],
  sterol: ['sterol', 'sterols', 'stanol', 'stanols'],
  oats: ['oat', 'oats', 'barley', 'beta-glucan', 'oatmeal'],
  nuts: ['nut', 'nuts', 'kacang'],
  soy: ['soy', 'soya'],
  dash: ['dash'],
  mediterranean: ['mediterranean'],
  supplement: ['supplement', 'supplements', 'suplemen', 'cinnamon', 'chromium', 'magnesium', 'vitamin'],
  hypoglycaemia: ['hypoglycaemia', 'hypoglycemia', 'hipoglisemia', 'hypo'],
  diabetes: ['diabetes', 'diabetic', 'kencing', 'prediabetes', 'glucose', 'glukosa'],
  blood_pressure: ['hypertension', 'darah', 'tekanan', 'bp', 'pressure'],
  fruit: ['fruit', 'fruits', 'buah'],
  vegetable: ['vegetable', 'vegetables', 'sayur', 'sayuran'],
  pattern: ['pattern', 'patterns', 'diet', 'eating', 'pemakanan'],
  hidden: ['hidden', 'ingredient', 'ingredients', 'bahan', 'benzoate', 'baking', 'disodium'],
  cooking: ['cooking', 'cook', 'masak', 'masakan', 'restaurant', 'eating-out', 'gravy', 'kuah', 'soup', 'sup'],
  pace: ['week', 'weekly', 'minggu', 'pace', 'fast', 'cepat'],
  remission: ['remission', 'reverse', 'pulih'],
  insulin: ['insulin'],
  referral: ['dietitian', 'dietician', 'doctor', 'doktor', 'pakar'],
};

const WORD_TO_CONCEPT = new Map();

for (const [concept, words] of Object.entries(CONCEPTS)) {
  for (const w of words) WORD_TO_CONCEPT.set(w, concept);
}

const STOPWORDS = new Set(
  (
    'the a an and or of to in on for is are be can could should would will i me my we you your it this that ' +
    'with as at by from about how what which who why when much many more most any some per day daily than ' +
    'do does did have has had not no yes if so but its am was were also just very okay ok please ' +
    'food foods product products healthy health good bad eat take intake people adults adult ' +
    'apa boleh saya ini itu yang dan untuk ke dari dengan tak tidak ada berapa makan banyak sikit sedikit ' +
    'macam mana kenapa adakah bagi pada atau juga lagi nak hendak perlu sahaja je ka ke la lah kah'
  ).split(' '),
);

/** Lower-case words of a text (letters, digits, hyphens). */
function words(text) {
  return String(text || '')
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .split(/[^a-z0-9-]+/)
    .filter((w) => w.length >= 2 && !STOPWORDS.has(w));
}

/** Concepts in a text; unknown words count as themselves. */
function conceptsOf(text) {
  const out = new Set();

  for (const w of words(text)) {
    const concept = WORD_TO_CONCEPT.get(w) || WORD_TO_CONCEPT.get(w.replace(/s$/, ''));

    if (concept) {
      out.add(concept);
    } else if (w.length >= 4 && !/^\d/.test(w)) {
      out.add(w.replace(/s$/, ''));
    }
  }

  return out;
}

// Concepts of every entry, worked out once per instance.
const INDEX = KB.entries.map((e) => ({
  entry: e,
  topic: conceptsOf(e.topic),
  text: conceptsOf(`${e.guidance} ${e.applies_to}`),
}));

/** The user's areas from the chat context, as KB areas. */
function userAreas(context) {
  const list = context && context.user && Array.isArray(context.user.health_areas)
    ? context.user.health_areas
    : [];

  return list.filter((a) => AREAS.includes(a));
}

/**
 * search_guidelines tool.
 * @param {object} context Chat context from the app.
 * @param {{query: string, health_area?: string}} input
 */
function searchGuidelines(context, input) {
  const query = typeof (input && input.query) === 'string' ? input.query.trim() : '';

  if (!query) return { error: 'Missing query.' };

  const asked = input.health_area && AREAS.includes(input.health_area) ? input.health_area : null;

  // An area the user asked about, or the user's own areas.
  // Users with no areas see every entry.
  const areas = asked ? [asked] : userAreas(context);
  const allowed = areas.length ? new Set([...areas, 'General']) : null;

  const q = conceptsOf(query);

  const scored = [];

  for (const item of INDEX) {
    if (allowed && !item.entry.areas.some((a) => allowed.has(a))) continue;

    let score = 0;

    for (const c of q) {
      if (item.topic.has(c)) score += 2;
      else if (item.text.has(c)) score += 1;
    }

    if (score >= MIN_SCORE) scored.push({ score, entry: item.entry });
  }

  scored.sort((a, b) => b.score - a.score || a.entry.id.localeCompare(b.entry.id));

  const top = scored.slice(0, MAX_RESULTS);

  if (!top.length) {
    return {
      found: false,
      message: 'No validated NutriPal guideline information was found for this question.',
      evidence_ids: [],
    };
  }

  return {
    found: true,
    entries: top.map(({ entry }) => ({
      id: entry.id,
      health_areas: entry.areas,
      topic: entry.topic,
      guidance: entry.guidance,
      applies_to: entry.applies_to,
      how_nutripal_uses_it: entry.nutripal_use,
      ...(entry.caution ? { caution: entry.caution } : {}),
      ...(entry.education_only ? { education_only: true } : {}),
      source: entry.source,
    })),
    evidence_ids: top.map(({ entry }) => entry.id),
  };
}

module.exports = {
  searchGuidelines,
  conceptsOf,
  KB_VERSION: KB.kb_version,
  KB_SIZE: KB.entries.length,
  AREAS,
  MIN_SCORE,
  MAX_RESULTS,
};
