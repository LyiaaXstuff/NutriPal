// =======================================================
// NUTRIPAL CLOUD FUNCTIONS
// =======================================================
//
// extractNutritionLabel
//   Callable from the app. Receives a JPEG of the
//   nutrition table (already cropped on the phone) and
//   returns the table as JSON, read by Claude.
//
// The Anthropic API key is a Firebase secret: it never
// ships inside the app.
//
//   firebase functions:secrets:set ANTHROPIC_API_KEY
// =======================================================

'use strict';

const { onCall, HttpsError } = require('firebase-functions/https');
const { defineSecret, defineString, defineBoolean } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');

const { readNutritionLabel, LabelReaderError } = require('./src/label_reader');

const ANTHROPIC_API_KEY = defineSecret('ANTHROPIC_API_KEY');

// Change without code edits, e.g. in functions/.env:
//   ANTHROPIC_MODEL=claude-sonnet-5-5
const ANTHROPIC_MODEL = defineString('ANTHROPIC_MODEL', {
  default: 'claude-haiku-5-5',
});

// Turn on once the app signs users in with Firebase Auth,
// so only NutriPal users can spend your API credits.
const REQUIRE_AUTH = defineBoolean('REQUIRE_AUTH', { default: false });

exports.extractNutritionLabel = onCall(
  {
    region: 'asia-southeast1',
    secrets: [ANTHROPIC_API_KEY],
    timeoutSeconds: 60,
    memory: '256MiB',
    // Caps how many scans can run at once (cost safety).
    maxInstances: 3,
    // Set to true after enabling App Check in the app.
    enforceAppCheck: false,
  },
  async (request) => {
    if (REQUIRE_AUTH.value() && !request.auth) {
      throw new HttpsError('unauthenticated', 'Please sign in to use AI reading.');
    }

    const started = Date.now();

    try {
      const result = await readNutritionLabel({
        data: request.data,
        apiKey: ANTHROPIC_API_KEY.value(),
        model: ANTHROPIC_MODEL.value(),
      });

      logger.info('nutrition label read', {
        model: result.model,
        rows: result.label.nutrients.length,
        columns: result.label.columns.length,
        usage: result.usage,
        ms: Date.now() - started,
      });

      return result;
    } catch (error) {
      if (error instanceof LabelReaderError) {
        logger.warn('nutrition label read failed', {
          code: error.code,
          message: error.message,
          detail: error.detail,
        });

        throw new HttpsError(error.code, error.message);
      }

      logger.error('unexpected error', error);

      throw new HttpsError('internal', 'AI reading failed.');
    }
  },
);
