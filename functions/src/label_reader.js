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

const TOOL_NAME = 'record_nutrition_table';

const SYSTEM_PROMPT = `You read packaged-food nutrition tables for NutriPal, a Malaysian nutrition app.

Read ONLY the nutrition information table (the bordered panel titled "Nutrition Information", "Maklumat Pemakanan", "Keterangan Pemakanan", "Nutrition Facts" or similar).
Ignore everything outside that table: logos, halal marks, sideways text, barcodes, ingredients, storage instructions, marketing text, other panels.

Rules:
- Copy what is printed. Never calculate, estimate, convert or fill in values that are not printed.
- Keep the table's row order. Include every nutrient row, including indented sub-rows (for example "- Asid Lemak tepu") and vitamins/minerals. Drop leading dashes or bullets from names.
- Write nutrient names exactly as printed, in the label's language. If a row is bilingual, keep both, e.g. "Tenaga / Energy".
- Skip descriptor rows that have no values, such as "yang terdiri daripada" or "of which".
- Skip claims and footnotes printed inside the table border below the rows, such as "a Cholesterol Free Food / Makanan Bebas Kolesterol" or "*Percent Daily Values are based on...". They are not nutrients.
- Columns: list the value columns left to right. basis is per_serving for "Per serving", "Setiap hidangan", "Per sachet", "Per 30 g" style columns; per_100g or per_100ml for 100 g / 100 ml columns; percent for %NRV / %DV columns; other otherwise.
- Every nutrient must have exactly one cell per column, in column order. A cell may hold several values, e.g. "230 kJ (55 kcal)" is two values.
- Units: use g, mg, µg, kcal, kJ, ml, IU or % exactly. In condensed fonts "g" can look like "9": a value such as "0.5g" is 0.5 g, not 0.59.
- "<0.1 g" means less_than true and amount 0.1.
- If a value cannot be read with confidence, set amount to null and printed to what you can see (or "?"). Do not guess.
- serving_size is the serving amount in g or ml if printed (e.g. "Saiz hidangan: 36g" -> 36 g). servings_per_package is the number of servings per pack if printed.
- If the image has no nutrition table, set is_nutrition_table to false and return empty lists.`;

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
    less_than: { type: 'boolean' },
    printed: {
      type: 'string',
      description: 'The cell text exactly as printed, e.g. "0.5g*".',
    },
  },
  required: ['amount', 'unit', 'printed'],
};

const TOOL_SCHEMA = {
  name: TOOL_NAME,
  description: 'Record the contents of the nutrition information table.',
  input_schema: {
    type: 'object',
    properties: {
      is_nutrition_table: { type: 'boolean' },
      serving_size: {
        type: ['object', 'null'],
        properties: {
          amount: { type: 'number' },
          unit: { type: 'string', enum: ['g', 'ml'] },
        },
        required: ['amount', 'unit'],
      },
      servings_per_package: { type: ['number', 'null'] },
      physical_serving: {
        type: ['object', 'null'],
        description: 'e.g. "2 keping", "1 sachet", "15 chips" if printed.',
        properties: {
          amount: { type: 'number' },
          name: { type: 'string' },
        },
        required: ['amount', 'name'],
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
        },
      },
      nutrients: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            name: { type: 'string' },
            cells: {
              type: 'array',
              description: 'One entry per column, in column order.',
              items: {
                type: 'object',
                properties: {
                  values: { type: 'array', items: VALUE_SCHEMA },
                },
                required: ['values'],
              },
            },
          },
          required: ['name', 'cells'],
        },
      },
      notes: {
        type: 'array',
        items: { type: 'string' },
        description: 'Anything unreadable or unusual, briefly.',
      },
    },
    required: ['is_nutrition_table', 'columns', 'nutrients'],
  },
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
    max_tokens: 4096,
    system: SYSTEM_PROMPT,
    tools: [TOOL_SCHEMA],
    tool_choice: { type: 'tool', name: TOOL_NAME },
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
 * @param {any} input tool_use input
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

          return {
            name: n.name.trim(),
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
 * @param {string} args.model model id, e.g. "claude-haiku-5-5"
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

  const toolUse = Array.isArray(body.content)
    ? body.content.find((block) => block.type === 'tool_use' && block.name === TOOL_NAME)
    : undefined;

  if (!toolUse || typeof toolUse.input !== 'object') {
    throw new LabelReaderError('internal', 'AI returned no table.');
  }

  return {
    label: sanitizeLabel(toolUse.input),
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
  TOOL_SCHEMA,
};
