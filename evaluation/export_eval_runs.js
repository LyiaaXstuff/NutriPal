'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const { createRequire } = require('node:module');

const requireFromFunctions = createRequire(
  path.join(__dirname, '..', 'functions', 'package.json'),
);
const { getApps, initializeApp } = requireFromFunctions('firebase-admin/app');
const { getFirestore, Timestamp } = requireFromFunctions('firebase-admin/firestore');

function toJsonValue(value) {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(toJsonValue);

  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, toJsonValue(item)]),
    );
  }

  return value;
}

async function main() {
  if (getApps().length === 0) initializeApp();

  const snapshot = await getFirestore()
    .collection('eval_runs')
    .orderBy('timestamp', 'asc')
    .get();
  const records = snapshot.docs.map((doc) => ({
    id: doc.id,
    ...toJsonValue(doc.data()),
  }));
  const outputPath = path.join(__dirname, 'results', 'eval_runs.json');

  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, `${JSON.stringify(records, null, 2)}\n`, 'utf8');

  console.log(`Exported ${records.length} evaluation runs to ${outputPath}`);
}

main().catch((error) => {
  console.error('Failed to export evaluation runs:', error.message);
  process.exitCode = 1;
});
