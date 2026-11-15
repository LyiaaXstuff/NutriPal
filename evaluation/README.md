# Evaluation tools

## Retrieval questions

`retrieval_questions.json` expected IDs were reviewed against KB 1.7.1 on 15 Nov 2026.

## How to run

From the repository root, run:

```powershell
node evaluation/retrieval_test.js
```

The script calls the local `searchGuidelines` implementation and reads the bundled KB; it does not call Claude or another AI API. It prints Hit@1, Hit@4, Precision@4, out-of-scope rejection results, and breakdowns by health area and language. Per-question results are written to `evaluation/results/retrieval_results.csv`.
