// =======================================================
// NUTRIPAL CLOUD FUNCTIONS
// =======================================================
//
// extractNutritionLabel
//   Callable from the app. Receives a JPEG of the
//   nutrition table (already cropped on the phone) and
//   returns the table as JSON, read by Claude.
//
// readProductName
//   Callable from the app. Receives the label photo when
//   no barcode was found in it and returns only the
//   product name and brand, if clearly printed.
//
// cleanUpDeletedUser
//   Runs when a Firebase Auth account is deleted and
//   removes everything under users/{uid} in Firestore
//   (safety net; the app deletes it first).
//
// askNutriPal
//   Callable from the app. Answers follow-up questions
//   about one analysed product (Layer 4: explains the
//   app's analysis, never changes its numbers).
//
// The Anthropic API key is a Firebase secret: it never
// ships inside the app.
//
//   firebase functions:secrets:set ANTHROPIC_API_KEY
// =======================================================

'use strict';

const { onCall, HttpsError } = require('firebase-functions/https');
const functionsV1 = require('firebase-functions/v1');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { defineSecret, defineString, defineBoolean } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');

const { readNutritionLabel, LabelReaderError } = require('./src/label_reader');
const { askNutriPal, AskNutriPalError } = require('./src/ask_nutripal');
const { readProductName } = require('./src/product_name');
const { deleteUserData } = require('./src/user_cleanup');

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

exports.readProductName = onCall(
  {
    region: 'asia-southeast1',
    secrets: [ANTHROPIC_API_KEY],
    timeoutSeconds: 30,
    memory: '256MiB',
    maxInstances: 3,
    enforceAppCheck: false,
  },
  async (request) => {
    if (REQUIRE_AUTH.value() && !request.auth) {
      throw new HttpsError('unauthenticated', 'Please sign in to use AI reading.');
    }

    const started = Date.now();

    try {
      const result = await readProductName({
        data: request.data,
        apiKey: ANTHROPIC_API_KEY.value(),
        model: ANTHROPIC_MODEL.value(),
      });

      logger.info('product name read', {
        model: result.model,
        found: result.product_name !== null,
        usage: result.usage,
        ms: Date.now() - started,
      });

      // Only the name and brand go back to the app.
      return { product_name: result.product_name, brand: result.brand };
    } catch (error) {
      if (error instanceof LabelReaderError) {
        logger.warn('product name read failed', {
          code: error.code,
          message: error.message,
          detail: error.detail,
        });

        throw new HttpsError(error.code, error.message);
      }

      logger.error('unexpected error', error);

      throw new HttpsError('internal', 'Product name reading failed.');
    }
  },
);

exports.askNutriPal = onCall(
  {
    region: 'asia-southeast1',
    secrets: [ANTHROPIC_API_KEY],
    timeoutSeconds: 60,
    memory: '256MiB',
    maxInstances: 3,
    enforceAppCheck: false,
  },
  async (request) => {
    if (REQUIRE_AUTH.value() && !request.auth) {
      throw new HttpsError('unauthenticated', 'Please sign in to use Ask NutriPal.');
    }

    const started = Date.now();

    try {
      const result = await askNutriPal({
        data: request.data,
        apiKey: ANTHROPIC_API_KEY.value(),
        model: ANTHROPIC_MODEL.value(),
      });

      logger.info('ask nutripal answered', {
        model: result.model,
        steps: result.steps.length,
        usage: result.usage,
        ms: Date.now() - started,
      });

      return { answer: result.answer, steps: result.steps };
    } catch (error) {
      if (error instanceof AskNutriPalError) {
        logger.warn('ask nutripal failed', {
          code: error.code,
          message: error.message,
          detail: error.detail,
        });

        throw new HttpsError(error.code, error.message);
      }

      logger.error('unexpected error', error);

      throw new HttpsError('internal', 'Ask NutriPal failed.');
    }
  },
);

// Auth "user deleted" events are only available as 1st
// generation triggers.
exports.cleanUpDeletedUser = functionsV1
  .region('asia-southeast1')
  .auth.user()
  .onDelete(async (user) => {
    if (getApps().length === 0) initializeApp();

    await deleteUserData({ db: getFirestore(), uid: user.uid });

    logger.info('deleted Firestore data of a deleted account');
  });
