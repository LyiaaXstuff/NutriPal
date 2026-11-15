'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const { CLAIM_LABELS, parseCsv } = require('./judge_gemini');

const HUMAN_CHECK_PATH = path.join(__dirname, 'human_check.csv');
const JUDGE_RESULTS_PATH = path.join(__dirname, 'results', 'judge_results.csv');
const BOOLEAN_LABELS = ['false', 'true'];

function parseBoolean(value) {
  const normalized = String(value || '').trim().toLowerCase();
  return normalized === 'true' || normalized === 'false' ? normalized : null;
}

function agreementStats(pairs, labels) {
  const usable = pairs.filter(
    ([human, judge]) => labels.includes(human) && labels.includes(judge),
  );
  if (usable.length === 0) return { count: 0, agreement: null, kappa: null };

  const humanCounts = new Map(labels.map((label) => [label, 0]));
  const judgeCounts = new Map(labels.map((label) => [label, 0]));
  let matches = 0;

  for (const [human, judge] of usable) {
    humanCounts.set(human, humanCounts.get(human) + 1);
    judgeCounts.set(judge, judgeCounts.get(judge) + 1);
    if (human === judge) matches++;
  }

  const observed = matches / usable.length;
  const expected = labels.reduce(
    (sum, label) =>
      sum + (humanCounts.get(label) / usable.length) * (judgeCounts.get(label) / usable.length),
    0,
  );

  return {
    count: usable.length,
    agreement: observed,
    kappa: expected === 1 ? null : (observed - expected) / (1 - expected),
  };
}

function validateAgainstJudge(humanRows, judgeRows) {
  const evaluatedRuns = new Map(judgeRows.map((row) => [row.run_id, row]));
  const humanClaims = [];
  const safetyPairs = [];
  const refusalPairs = [];

  for (const row of humanRows) {
    const judgedRun = evaluatedRuns.get(row.run_id);
    if (!judgedRun) {
      throw new Error(`Human check run ${row.run_id} is missing from judge_results.csv.`);
    }

    if (row.row_type === 'run') {
      const humanSafety = parseBoolean(row.human_safety_pass);
      const judgeSafety = parseBoolean(judgedRun.safety_pass);
      if (humanSafety !== null && judgeSafety !== null) {
        safetyPairs.push([humanSafety, judgeSafety]);
      }

      const humanRefusal = parseBoolean(row.human_refused_correctly);
      const judgeRefusal = parseBoolean(judgedRun.refused_correctly);
      if (humanRefusal !== null && judgeRefusal !== null) {
        refusalPairs.push([humanRefusal, judgeRefusal]);
      }
    } else if (row.row_type === 'claim') {
      let claims;
      try {
        claims = JSON.parse(judgedRun.claims_json);
      } catch (_) {
        throw new Error(`Invalid claims_json for run ${row.run_id}.`);
      }

      const index = Number(row.claim_index) - 1;
      const claim = claims[index];
      if (
        !claim ||
        claim.claim !== row.claim ||
        (row.judge_label && claim.label !== row.judge_label)
      ) {
        throw new Error(
          `Human check claim ${row.run_id}/${row.claim_index} does not match the judge output.`,
        );
      }

      if (CLAIM_LABELS.includes(row.human_label)) {
        humanClaims.push([row.human_label, claim.label]);
      }
    } else {
      throw new Error(`Unknown human_check row_type: ${row.row_type}`);
    }
  }

  return {
    safety: agreementStats(safetyPairs, BOOLEAN_LABELS),
    refusal: agreementStats(refusalPairs, BOOLEAN_LABELS),
    claims: agreementStats(humanClaims, CLAIM_LABELS),
  };
}

function formatStats(label, stats) {
  const agreement = stats.agreement === null
    ? 'n/a'
    : `${(stats.agreement * 100).toFixed(1)}%`;
  const kappa = stats.kappa === null ? 'n/a' : stats.kappa.toFixed(3);
  console.log(`${label}: n=${stats.count}; agreement=${agreement}; Cohen's kappa=${kappa}`);
}

async function main() {
  const [humanText, judgeText] = await Promise.all([
    fs.readFile(HUMAN_CHECK_PATH, 'utf8'),
    fs.readFile(JUDGE_RESULTS_PATH, 'utf8'),
  ]);
  const humanRows = parseCsv(humanText);
  const judgeRows = parseCsv(judgeText);
  const stats = validateAgainstJudge(humanRows, judgeRows);

  console.log('Human vs Gemini judge agreement:');
  formatStats('safety_pass', stats.safety);
  formatStats('refused_correctly', stats.refusal);
  formatStats('per-claim labels', stats.claims);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`Judge agreement failed: ${error.message}`);
    process.exitCode = 1;
  });
}

module.exports = { parseBoolean, agreementStats, validateAgainstJudge, formatStats };
