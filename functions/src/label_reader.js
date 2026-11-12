// =======================================================
// NUTRITION LABEL READER (Claude vision)
// =======================================================
//
// Pure logic, no Firebase imports, so it can be tested
// with `npm test` and a fake fetch.
//
// The prompt and output schema live here on the server:
// the app can only ask "read this nutrition table", never
// send its own prompt, so a leaked endpoint cannot be used
// as a general-purpose Claude proxy.
// =======================================================

'use strict';

const ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages';
const ANTHROPIC_VERSION = '2023-06-01';

const ALLOWED_MEDIA_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

// Base64 of a ~6 MB image. The API allows 10 MB; the app
// sends ~0.5 MB crops, so anything near this is misuse.
const MAX_BASE64_LENGTH = 8 * 1024 * 1024;

const SYSTEM_PROMPT = `You read packaged-food nutrition tables for NutriPal, a Malaysian nutrition app.

Read ONLY the nutrition information table (the bordered panel titled "Nutrition Information", "Maklumat Pemakanan", "Keterangan Pemakanan", "Nutrition Facts" or similar).
Ignore everything outside that table: logos, halal marks, sideways text, barcodes, ingredients, storage instructions, marketing text, other panels.

Rules:
- Copy what is printed. Never calculate, estimate, convert or fill in values that are not printed.
- Keep the table's row order. Include every nutrient row, including indented sub-rows (for example "- Asid Lemak tepu") and vitamins/minerals. Drop leading dashes or bullets from names.
- Write nutrient names exactly as printed, in the label's language. If a row is bilingual, keep both, e.g. "Tenaga / Energy".
- Labels may also be printed in Arabic, Chinese, Tamil, Thai or another script, alone or next to English / Malay. Read those parts too and copy them in their own script, e.g. "Protein / بروتين". Never replace printed text with a translation.
- english_name: when the printed name has no English or Malay part (e.g. only "بروتين"), give the standard English nutrient name ("Protein"). Otherwise leave it empty.
- Write every amount with Western digits: Arabic-Indic digits such as "٢٫٥" are 2.5.
- Skip descriptor rows that have no values, such as "yang terdiri daripada" or "of which".
- Skip claims and footnotes printed inside the table border below the rows, such as "a Cholesterol Free Food / Makanan Bebas Kolesterol" or "*Percent Daily Values are based on...". They are not nutrients.
- Columns: list the value columns left to right. basis is per_serving for "Per serving", "Setiap hidangan", "Per sachet", "Per 30 g" style columns; per_100g or per_100ml for 100 g / 100 ml columns; percent for %NRV / %DV columns; other otherwise.
- Every nutrient must have exactly one cell per column, in column order. A cell may hold several values, e.g. "230 kJ (55 kcal)" is two values.
- Units: use g, mg, µg, kcal, kJ, ml, IU or % exactly. In condensed fonts "g" can look like "9": a value such as "0.5g" is 0.5 g, not 0.59.
- "<0.1 g" means less_than true and amount 0.1.
- If a value cannot be read with confidence, set amount to null and printed to what you can see (or "?"). Do not guess.
- serving_size is the serving amount in g or ml if printed (e.g. "Saiz hidangan: 36g" -> 36 g). servings_per_package is the number of servings per pack if printed.
- If the image has no nutrition table, set is_nutrition_table to false and return empty lists.`;

// Structured output (JSON schema). Newer models such as
// Claude Sonnet 5.5 do not support forcing a tool call, so
// the table is returned as JSON that must match this
// schema (output_config.format). Every object lists all of
// its properties as required and allows no extra ones.
const VALUE_SCHEMA = {
  type: 'object',
  properties: {
    amount: {
      type: ['number', 'null'],
      description: 'Numeric value as printed, or null if unreadable.',
    },
    unit: {
      type: 'string',
      enum: ['g', 'mg', 'µg', 'kcal', 'kJ', 'ml', 'IU', '%', ''],
    },
    less_than: { type: 'boolean', description: 'True for "<0.1 g".' },
    printed: {
      type: 'string',
      description: 'The cell text exactly as printed, e.g. "0.5g*".',
    },
  },
  required: ['amount', 'unit', 'less_than', 'printed'],
  additionalProperties: false,
};

const OUTPUT_SCHEMA = {
  type: 'object',
  properties: {
    is_nutrition_table: { type: 'boolean' },
    serving_size: {
      type: ['object', 'null'],
      description: 'Serving amount in g or ml if printed, otherwise null.',
      properties: {
        amount: { type: 'number' },
        unit: { type: 'string', enum: ['g', 'ml'] },
      },
      required: ['amount', 'unit'],
      additionalProperties: false,
    },
    servings_per_package: {
      type: ['number', 'null'],
      description: 'Servings per pack if printed, otherwise null.',
    },
    physical_serving: {
      type: ['object', 'null'],
      description: 'e.g. "2 keping", "1 sachet", "15 chips" if printed, otherwise null.',
      properties: {
        amount: { type: 'number' },
        name: { type: 'string' },
      },
      required: ['amount', 'name'],
      additionalProperties: false,
    },
    columns: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          label: { type: 'string', description: 'Header as printed.' },
          basis: {
            type: 'string',
            enum: ['per_serving', 'per_100g', 'per_100ml', 'percent', 'other'],
          },
        },
        required: ['label', 'basis'],
        additionalProperties: false,
      },
    },
    nutrients: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Name exactly as printed.' },
          english_name: {
            type: 'string',
            description:
              'Standard English name only when the printed name has no English or Malay part, otherwise "".',
          },
          cells: {
            type: 'array',
            description: 'One entry per column, in column order.',
            items: {
              type: 'object',
              properties: {
                values: { type: 'array', items: VALUE_SCHEMA },
              },
              required: ['values'],
              additionalProperties: false,
            },
          },
        },
        required: ['name', 'english_name', 'cells'],
        additionalProperties: false,
      },
    },
    notes: {
      type: 'array',
      items: { type: 'string' },
      description: 'Anything unreadable or unusual, briefly. Empty if none.',
    },
  },
  required: [
    'is_nutrition_table',
    'serving_size',
    'servings_per_package',
    'physical_serving',
    'columns',
    'nutrients',
    'notes',
  ],
  additionalProperties: false,
};

class LabelReaderError extends Error {
  /**
   * @param {string} code Firebase HttpsError code.
   * @param {string} message Safe message for the app.
   */
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

/**
 * Checks the request coming from the app.
 * @param {any} data
 * @returns {{imageBase64: string, mediaType: string}}
 */
function validateRequest(data) {
  if (!data || typeof data !== 'object') {
    throw new LabelReaderError('invalid-argument', 'Missing request data.');
  }

  const { imageBase64, mediaType } = data;

  if (typeof imageBase64 !== 'string' || imageBase64.length < 100) {
    throw new LabelReaderError('invalid-argument', 'Missing image.');
  }

  if (imageBase64.length > MAX_BASE64_LENGTH) {
    throw new LabelReaderError('invalid-argument', 'Image is too large.');
  }

  if (!/^[A-Za-z0-9+/=\r\n]+$/.test(imageBase64)) {
    throw new LabelReaderError('invalid-argument', 'Image must be base64.');
  }

  const type = mediaType || 'image/jpeg';

  if (!ALLOWED_MEDIA_TYPES.includes(type)) {
    throw new LabelReaderError('invalid-argument', 'Unsupported image type.');
  }

  return { imageBase64: imageBase64.replace(/[\r\n]/g, ''), mediaType: type };
}

/**
 * Builds the Messages API request body.
 */
function buildRequestBody({ imageBase64, mediaType, model }) {
  return {
    model,
    max_tokens: 8192,
    system: SYSTEM_PROMPT,
    output_config: {
      format: { type: 'json_schema', schema: OUTPUT_SCHEMA },
    },
    messages: [
      {
        role: 'user',
        content: [
          {
            type: 'image',
            source: { type: 'base64', media_type: mediaType, data: imageBase64 },
          },
          {
            type: 'text',
            text: 'Read the nutrition information table in this photo and record it.',
          },
        ],
      },
    ],
  };
}

/**
 * Makes sure Claude's answer has the shape the app expects,
 * dropping anything malformed instead of failing the scan.
 * @param {any} input parsed JSON from Claude
 */
function sanitizeLabel(input) {
  const asNumber = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : null);
  const asString = (v) => (typeof v === 'string' ? v : '');

  const columns = Array.isArray(input.columns)
    ? input.columns.map((c) => ({
        label: asString(c && c.label),
        basis: ['per_serving', 'per_100g', 'per_100ml', 'percent', 'other'].includes(
          c && c.basis,
        )
          ? c.basis
          : 'other',
      }))
    : [];

  const nutrients = Array.isArray(input.nutrients)
    ? input.nutrients
        .filter((n) => n && typeof n.name === 'string' && n.name.trim())
        .map((n) => {
          const cells = Array.isArray(n.cells) ? n.cells : [];

          const english = typeof n.english_name === 'string' ? n.english_name.trim() : '';

          return {
            name: n.name.trim(),
            ...(english ? { english_name: english } : {}),
            cells: columns.map((_, i) => {
              const cell = cells[i];
              const values = cell && Array.isArray(cell.values) ? cell.values : [];

              return {
                values: values
                  .filter((v) => v && typeof v === 'object')
                  .map((v) => ({
                    amount: asNumber(v.amount),
                    unit: asString(v.unit),
                    less_than: v.less_than === true,
                    printed: asString(v.printed),
                  })),
              };
            }),
          };
        })
    : [];

  const serving =
    input.serving_size &&
    asNumber(input.serving_size.amount) !== null &&
    ['g', 'ml'].includes(input.serving_size.unit)
      ? { amount: input.serving_size.amount, unit: input.serving_size.unit }
      : null;

  const physical =
    input.physical_serving &&
    asNumber(input.physical_serving.amount) !== null &&
    typeof input.physical_serving.name === 'string'
      ? { amount: input.physical_serving.amount, name: input.physical_serving.name }
      : null;

  return {
    is_nutrition_table: input.is_nutrition_table !== false,
    serving_size: serving,
    servings_per_package: asNumber(input.servings_per_package),
    physical_serving: physical,
    columns,
    nutrients,
    notes: Array.isArray(input.notes) ? input.notes.filter((s) => typeof s === 'string') : [],
  };
}

/**
 * Sends the image to Claude and returns the sanitized table.
 *
 * @param {object} args
 * @param {any} args.data request data from the app
 * @param {string} args.apiKey Anthropic API key
 * @param {string} args.model model id, e.g. "claude-sonnet-5-5"
 * @param {typeof fetch} [args.fetchImpl] injectable for tests
 */
async function readNutritionLabel({ data, apiKey, model, fetchImpl = fetch }) {
  const request = validateRequest(data);

  if (!apiKey) {
    throw new LabelReaderError('failed-precondition', 'AI reading is not configured.');
  }

  let response;

  try {
    response = await fetchImpl(ANTHROPIC_URL, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': ANTHROPIC_VERSION,
      },
      body: JSON.stringify(buildRequestBody({ ...request, model })),
    });
  } catch (error) {
    throw new LabelReaderError('unavailable', 'Could not reach the AI service.');
  }

  if (!response.ok) {
    const status = response.status;
    const code =
      status === 429 || status === 529
        ? 'resource-exhausted'
        : status >= 500
          ? 'unavailable'
          : 'internal';

    let detail = '';

    try {
      detail = JSON.stringify(await response.json()).slice(0, 300);
    } catch (_) {
      // ignore
    }

    const error = new LabelReaderError(code, `AI service error (${status}).`);
    error.detail = detail;
    throw error;
  }

  const body = await response.json();

  if (body.stop_reason === 'refusal') {
    throw new LabelReaderError('internal', 'AI declined to read this image.');
  }

  if (body.stop_reason === 'max_tokens') {
    throw new LabelReaderError('internal', 'AI answer was cut off. Please try again.');
  }

  const text = Array.isArray(body.content)
    ? body.content
        .filter((block) => block.type === 'text' && typeof block.text === 'string')
        .map((block) => block.text)
        .join('')
    : '';

  let parsed;

  try {
    parsed = JSON.parse(text);
  } catch (_) {
    parsed = null;
  }

  if (!parsed || typeof parsed !== 'object') {
    throw new LabelReaderError('internal', 'AI returned no table.');
  }

  return {
    label: sanitizeLabel(parsed),
    model: body.model || model,
    usage: body.usage || null,
  };
}

module.exports = {
  readNutritionLabel,
  validateRequest,
  buildRequestBody,
  sanitizeLabel,
  LabelReaderError,
  SYSTEM_PROMPT,
  OUTPUT_SCHEMA,
};
