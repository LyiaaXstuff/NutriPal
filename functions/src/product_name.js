// =======================================================
// PRODUCT NAME READER (Claude vision)
// =======================================================
//
// Finds the product's name on the label photo, for scans
// where no barcode was found in the photo. It only returns
// a name and brand: the nutrition values are never read
// here (they come from the nutrition table reader and the
// user's confirmation).
//
// Pure logic, no Firebase imports, so it can be tested
// with `npm test` and a fake fetch. The prompt and schema
// stay on the server, like the label reader.
// =======================================================

'use strict';

const { validateRequest, LabelReaderError } = require('./label_reader');

const ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages';
const ANTHROPIC_VERSION = '2023-06-01';

const MAX_NAME_LENGTH = 80;

const SYSTEM_PROMPT = `You find the product name on photos of packaged food for NutriPal, a Malaysian nutrition app.

The photo was taken to read the nutrition table, so it usually shows the back or side of the pack. Look at the rest of the pack for the product's name.

Return the name only when it is clearly printed, for example a large product title, the product description ("Roti Putih / White Bread", "Biskut Krim Coklat"), or the brand with its variant.

Never return any of these as the name:
- text from the nutrition table
- ingredients, allergen, storage or preparation statements
- the manufacturer's, importer's or distributor's company name or address, websites, phone numbers
- net weight, halal text, barcodes, batch or expiry codes
- marketing slogans or claims ("Less sugar", "High in calcium", "New!")

Copy the name as printed (Malay, English or both). Do not translate it, and never make up a name from the ingredients or nutrition values.
brand: only the brand name (e.g. "Gardenia") when clearly printed, otherwise null.
confidence: "high" only when you can clearly read a real product name; otherwise "low".
If no product name is clearly printed, set product_name to null. No name is better than a guess.`;

const OUTPUT_SCHEMA = {
  type: 'object',
  properties: {
    product_name: {
      type: ['string', 'null'],
      description: 'Product name as printed, or null if none is clearly printed.',
    },
    brand: {
      type: ['string', 'null'],
      description: 'Brand name as printed, or null.',
    },
    confidence: { type: 'string', enum: ['high', 'low'] },
  },
  required: ['product_name', 'brand', 'confidence'],
  additionalProperties: false,
};

// Text that is never a product name, even if Claude
// returns it.
const NOT_A_NAME = [
  /nutrition/i,
  /maklumat\s+pemakanan/i,
  /keterangan\s+pemakanan/i,
  /\bingredients?\b/i,
  /\bramuan\b/i,
  /\bkandungan\b/i,
  /dikilang|dibuat\s+oleh|diedar|pengedar/i,
  /manufactured|distributed|imported|packed\s+by/i,
  /sdn\.?\s*bhd|\bbhd\b|\bberhad\b|\bltd\b|\bpte\b/i,
  /berat\s+bersih|net\s*(wt|weight)/i,
  /\bhalal\b/i,
  /www\.|https?:|\.com\b|\.my\b/i,
  /best\s+before|tarikh|expiry|\bexp\b/i,
];

/**
 * Builds the Messages API request body.
 */
function buildRequestBody({ imageBase64, mediaType, model }) {
  return {
    model,
    max_tokens: 300,
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
            text: 'What is the name of this product, if it is printed on the pack?',
          },
        ],
      },
    ],
  };
}

/**
 * Cleans one name: trims, joins spaces, removes quotes
 * and rejects anything that is not a plausible name.
 * @param {any} value
 * @returns {string|null}
 */
function cleanName(value) {
  if (typeof value !== 'string') return null;

  const name = value
    .replace(/\s+/g, ' ')
    .replace(/^["'“”‘’\s]+|["'“”‘’\s]+$/g, '')
    .trim();

  if (name.length < 2 || name.length > MAX_NAME_LENGTH) return null;

  // Needs at least two letters (any script).
  if ((name.match(/\p{L}/gu) || []).length < 2) return null;

  if (NOT_A_NAME.some((pattern) => pattern.test(name))) return null;

  return name;
}

/**
 * Makes sure Claude's answer is safe to show as a name.
 * Low-confidence answers are dropped: the app then keeps
 * "Scanned product" and the user can rename it.
 * @param {any} input parsed JSON from Claude
 * @returns {{product_name: string|null, brand: string|null}}
 */
function sanitizeName(input) {
  if (!input || typeof input !== 'object' || input.confidence !== 'high') {
    return { product_name: null, brand: null };
  }

  const productName = cleanName(input.product_name);

  if (!productName) return { product_name: null, brand: null };

  const brand = cleanName(input.brand);

  return { product_name: productName, brand };
}

/**
 * Sends the photo to Claude and returns the product name,
 * or nulls when none is clearly printed.
 *
 * @param {object} args
 * @param {any} args.data request data from the app
 * @param {string} args.apiKey Anthropic API key
 * @param {string} args.model model id
 * @param {typeof fetch} [args.fetchImpl] injectable for tests
 */
async function readProductName({ data, apiKey, model, fetchImpl = fetch }) {
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

    const error = new LabelReaderError(code, `AI service error (${status}).`);

    try {
      error.detail = JSON.stringify(await response.json()).slice(0, 300);
    } catch (_) {
      // ignore
    }

    throw error;
  }

  const body = await response.json();

  const text = Array.isArray(body.content)
    ? body.content
        .filter((block) => block.type === 'text' && typeof block.text === 'string')
        .map((block) => block.text)
        .join('')
    : '';

  let parsed = null;

  try {
    parsed = JSON.parse(text);
  } catch (_) {
    parsed = null;
  }

  // Refusals, cut-off or unreadable answers: no name.
  // Finding a name is optional, so this is not an error.
  const result =
    body.stop_reason === 'refusal' || body.stop_reason === 'max_tokens'
      ? { product_name: null, brand: null }
      : sanitizeName(parsed);

  return {
    ...result,
    model: body.model || model,
    usage: body.usage || null,
  };
}

module.exports = {
  readProductName,
  buildRequestBody,
  sanitizeName,
  cleanName,
  SYSTEM_PROMPT,
  OUTPUT_SCHEMA,
};
