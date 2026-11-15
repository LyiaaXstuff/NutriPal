'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const { searchGuidelines } = require('../functions/src/guidelines');

const QUESTIONS_PATH = path.join(__dirname, 'retrieval_questions.json');
const RESULTS_PATH = path.join(__dirname, 'results', 'retrieval_results.csv');
const VALID_AREAS = new Set([
  'Diabetes',
  'Blood pressure',
  'Cholesterol',
  'Weight',
  'General',
]);
const VALID_LANGUAGES = new Set(['English', 'BM/mixed']);

function validateQuestions(data) {
  if (!data || !Array.isArray(data.questions)) {
    throw new Error('retrieval_questions.json must contain a questions array.');
  }

  const ids = new Set();

  for (const question of data.questions) {
    if (!question || typeof question.id !== 'string' || ids.has(question.id)) {
      throw new Error('Every question must have a unique string id.');
    }

    ids.add(question.id);

    if (typeof question.question !== 'string' || !question.question.trim()) {
      throw new Error(`${question.id} must have a non-empty question.`);
    }

    if (
      question.health_area !== null &&
      !VALID_AREAS.has(question.health_area)
    ) {
      throw new Error(`${question.id} has an invalid health_area.`);
    }

    if (
      !Array.isArray(question.expected_entry_ids) ||
      question.expected_entry_ids.some((id) => typeof id !== 'string')
    ) {
      throw new Error(`${question.id} must have an expected_entry_ids array.`);
    }

    if (typeof question.should_match !== 'boolean') {
      throw new Error(`${question.id} must have a boolean should_match.`);
    }

    if (!VALID_LANGUAGES.has(question.language)) {
      throw new Error(`${question.id} must be labeled English or BM/mixed.`);
    }

    if (!question.should_match && question.expected_entry_ids.length !== 0) {
      throw new Error(`${question.id} should have no expected IDs when should_match is false.`);
    }
  }
}

function evaluateQuestion(question) {
  const result = searchGuidelines({}, {
    query: question.question,
    ...(question.health_area ? { health_area: question.health_area } : {}),
  });
  const returnedIds = (result.entries || []).map((entry) => entry.id);
  const expected = new Set(question.expected_entry_ids);
  const expectedReturned = returnedIds.filter((id) => expected.has(id));

  return {
    ...question,
    found: result.found === true,
    returnedIds,
    expectedReturned,
    wronglyReturnedIds: question.should_match
      ? []
      : returnedIds,
    hitAt1: question.should_match && returnedIds.length > 0 && expected.has(returnedIds[0]),
    hitAt4: question.should_match && expectedReturned.length > 0,
    precisionAt4: question.should_match
      ? (returnedIds.length === 0 ? 0 : expectedReturned.length / returnedIds.length)
      : null,
    correctRejection: !question.should_match && result.found !== true,
  };
}

function percentage(numerator, denominator) {
  return denominator === 0 ? 'n/a' : `${((numerator / denominator) * 100).toFixed(1)}%`;
}

function metricSummary(label, items) {
  const answerable = items.filter((item) => item.should_match);
  const returnedCount = answerable.reduce((total, item) => total + item.returnedIds.length, 0);
  const expectedReturnedCount = answerable.reduce(
    (total, item) => total + item.expectedReturned.length,
    0,
  );
  const hit1Count = answerable.filter((item) => item.hitAt1).length;
  const hit4Count = answerable.filter((item) => item.hitAt4).length;
  const outOfScope = items.filter((item) => !item.should_match);
  const rejectedCount = outOfScope.filter((item) => item.correctRejection).length;

  console.log(
    `${label}: answerable ${answerable.length}; ` +
      `Hit@1 ${hit1Count}/${answerable.length} (${percentage(hit1Count, answerable.length)}); ` +
      `Hit@4 ${hit4Count}/${answerable.length} (${percentage(hit4Count, answerable.length)}); ` +
      `Precision@4 ${expectedReturnedCount}/${returnedCount} ` +
      `(${percentage(expectedReturnedCount, returnedCount)}); ` +
      `correct rejection ${rejectedCount}/${outOfScope.length} ` +
      `(${percentage(rejectedCount, outOfScope.length)})`,
  );
}

function csvCell(value) {
  const text = value == null ? '' : String(value);
  return `"${text.replaceAll('"', '""')}"`;
}

function toCsv(results) {
  const columns = [
    'id',
    'question',
    'health_area',
    'language',
    'should_match',
    'found',
    'expected_entry_ids',
    'returned_entry_ids',
    'expected_returned_entry_ids',
    'hit_at_1',
    'hit_at_4',
    'precision_at_4',
    'correct_rejection',
    'wrongly_returned_entry_ids',
  ];
  const lines = [
    columns.join(','),
    ...results.map((result) =>
      [
        result.id,
        result.question,
        result.health_area ?? 'Unspecified',
        result.language,
        result.should_match,
        result.found,
        result.expected_entry_ids.join(';'),
        result.returnedIds.join(';'),
        result.expectedReturned.join(';'),
        result.should_match ? result.hitAt1 : '',
        result.should_match ? result.hitAt4 : '',
        result.precisionAt4 == null ? '' : result.precisionAt4.toFixed(4),
        result.should_match ? '' : result.correctRejection,
        result.wronglyReturnedIds.join(';'),
      ].map(csvCell).join(','),
    ),
  ];

  return `${lines.join('\n')}\n`;
}

async function main() {
  const questionData = JSON.parse(await fs.readFile(QUESTIONS_PATH, 'utf8'));
  validateQuestions(questionData);

  const results = questionData.questions.map(evaluateQuestion);

  console.log(`Retrieval evaluation for KB ${questionData.kb_version}`);
  metricSummary('Overall', results);

  const areas = new Set(
    results.map((result) => result.health_area ?? 'Unspecified'),
  );

  console.log('\nBy health area:');
  for (const area of areas) {
    metricSummary(
      area,
      results.filter((result) => (result.health_area ?? 'Unspecified') === area),
    );
  }

  console.log('\nBy language:');
  for (const language of VALID_LANGUAGES) {
    metricSummary(
      language,
      results.filter((result) => result.language === language),
    );
  }

  for (const result of results.filter((item) => !item.should_match)) {
    console.log(
      `${result.id} ${result.correctRejection ? 'correctly rejected' : 'unexpected entries'}: ` +
        `${result.wronglyReturnedIds.length ? result.wronglyReturnedIds.join(', ') : '(none)'}`,
    );
  }

  await fs.mkdir(path.dirname(RESULTS_PATH), { recursive: true });
  await fs.writeFile(RESULTS_PATH, toCsv(results), 'utf8');
  console.log(`\nWrote ${results.length} question results to ${RESULTS_PATH}`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error('Retrieval evaluation failed:', error.message);
    process.exitCode = 1;
  });
}

module.exports = { validateQuestions, evaluateQuestion, metricSummary, toCsv };
